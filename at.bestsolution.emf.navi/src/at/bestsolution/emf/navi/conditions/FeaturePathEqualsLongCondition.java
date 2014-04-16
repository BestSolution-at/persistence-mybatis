package at.bestsolution.emf.navi.conditions;

import org.eclipse.emf.ecore.EObject;

import at.bestsolution.emf.navi.FeaturePath;
import at.bestsolution.emf.navi.FeaturePathSegment;
import at.bestsolution.emf.navi.FeaturePathUtil;

public class FeaturePathEqualsLongCondition extends FeaturePathCondition {

	private final long equals;
	
	public FeaturePathEqualsLongCondition(FeaturePath path, long equals) {
		super(path);
		this.equals = equals;
		FeaturePathSegment lastSegment = path.getSegments().get(path.getSegments().size()-1);
		if (!lastSegment.feature.getEType().getInstanceClassName().equals("long")) {
			throw new IllegalArgumentException("feature path must point to an long value");
		}
	}

	@Override
	public boolean matches(EObject object) {
		final long result = ((Long)FeaturePathUtil.get(object, path)).longValue();
		return result == equals;
	}

}